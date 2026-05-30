using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Books.Commands;
using Inkril.Application.Features.Books.Queries;
using Microsoft.EntityFrameworkCore;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using UglyToad.PdfPig;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class BooksController(IMediator mediator, ICurrentUserService currentUser, IUnitOfWork uow, IWebHostEnvironment env) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] GetBooksQuery query, CancellationToken ct)
    {
        var result = await mediator.Send(query, ct);

        // Compute a weak ETag from the sorted IDs of the returned page.
        // Changes whenever books are added, removed, or a filter changes the set.
        // Clients that send If-None-Match get a 304 and skip JSON parsing entirely.
        var idBytes = System.Text.Encoding.UTF8.GetBytes(
            string.Concat(result.Items.OrderBy(b => b.Id).Select(b => b.Id.ToString("N"))));
        var hash  = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(idBytes));
        var etag  = $"\"{hash[..16]}\"";

        if (Request.Headers.IfNoneMatch.Contains(etag))
            return StatusCode(StatusCodes.Status304NotModified);

        Response.Headers.ETag         = etag;
        // Private — each user may see a different visibility subset.
        // max-age=30 lets fast back-navigations skip a round-trip entirely.
        Response.Headers.CacheControl = "private, max-age=30";

        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new GetBookByIdQuery(id, currentUser.UserId), ct);
        return result.Succeeded ? Ok(result.Value) : NotFound(new { message = result.Errors[0] });
    }

    /// <summary>
    /// Returns the PDF storage path only after verifying the user owns the book.
    /// Admins (desktop role) bypass the ownership check.
    /// This is the controlled gate — FilePath is NOT included in the public BookDetailDto.
    /// </summary>
    [HttpGet("{id:guid}/read-url")]
    public async Task<IActionResult> GetReadUrl(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(
            new GetBookReadUrlQuery(id, currentUser.UserId, currentUser.IsInRole("desktop")), ct);
        return result.Succeeded
            ? Ok(new { filePath = result.Value })
            : Forbid();
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateBookCommand cmd, CancellationToken ct)
    {
        // Desktop (admin) users can create public or private books freely.
        // Mobile users may only upload personal/private books (IsPublic = false).
        // This prevents mobile users from publishing books to the shared library.
        if (!currentUser.IsInRole("desktop") && cmd.IsPublic)
            return Problem(
                detail: "Mobile users can only upload private books. Set isPublic to false.",
                statusCode: StatusCodes.Status403Forbidden,
                title: "Forbidden");

        var result = await mediator.Send(cmd, ct);
        return ToResult(result, id => CreatedAtAction(nameof(GetById), new { id }, new { id }));
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateBookCommand cmd, CancellationToken ct)
    {
        if (id != cmd.Id) return BadRequest("Route ID and body ID do not match.");
        var result = await mediator.Send(cmd, ct);
        return ToResult(result, NoContent());
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var book = await uow.Books.GetByIdAsync(id, ct);
        if (book is null) return NotFound();
        uow.Books.SoftDelete(book);
        await uow.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPost("{id:guid}/upload-cover")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<IActionResult> UploadCover(Guid id, IFormFile file, CancellationToken ct)
    {
        if (file.Length == 0) return BadRequest(new { errors = new[] { "No file provided." } });

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp"))
            return BadRequest(new { errors = new[] { "Only JPG, PNG and WebP are accepted for cover images." } });

        // Magic byte validation — checks the actual file content, not just the extension (§5)
        if (!await IsValidImageAsync(file))
            return BadRequest(new { errors = new[] { "File content does not match a recognised image format (JPEG/PNG/WebP)." } });

        var book = await uow.Books.GetByIdAsync(id, ct);
        if (book is null) return NotFound();

        // Mobile users may only modify books they created (private books).
        // Desktop admins can modify any book.
        if (!currentUser.IsInRole("desktop") && book.CreatedBy != currentUser.UserName)
            return Forbid();

        var uploadsDir = Path.Combine(env.WebRootPath, "uploads", "covers");
        Directory.CreateDirectory(uploadsDir);

        var fileName = $"{id}{ext}";
        var filePath = Path.Combine(uploadsDir, fileName);

        await using (var stream = System.IO.File.Create(filePath))
            await file.CopyToAsync(stream, ct);

        book.CoverImageUrl = $"/uploads/covers/{fileName}";
        book.UpdatedAt = DateTime.UtcNow;
        uow.Books.Update(book);
        await uow.SaveChangesAsync(ct);

        return Ok(new { coverImageUrl = book.CoverImageUrl });
    }

    [HttpPost("{id:guid}/upload-pdf")]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<IActionResult> UploadPdf(Guid id, IFormFile file, CancellationToken ct)
    {
        if (file.Length == 0) return BadRequest(new { errors = new[] { "No file provided." } });

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext != ".pdf")
            return BadRequest(new { errors = new[] { "Only PDF files are accepted." } });

        // Magic byte validation — %PDF header (25 50 44 46) (§5)
        if (!await IsValidPdfAsync(file))
            return BadRequest(new { errors = new[] { "File content does not match PDF format." } });

        var book = await uow.Books.GetByIdAsync(id, ct);
        if (book is null) return NotFound();

        // Mobile users may only upload PDFs to books they created (private books).
        // Desktop admins can upload to any book.
        if (!currentUser.IsInRole("desktop") && book.CreatedBy != currentUser.UserName)
            return Forbid();

        var uploadsDir = Path.Combine(env.WebRootPath, "uploads", "books");
        Directory.CreateDirectory(uploadsDir);

        var fileName = $"{id}.pdf";
        var filePath = Path.Combine(uploadsDir, fileName);

        await using (var stream = System.IO.File.Create(filePath))
            await file.CopyToAsync(stream, ct);

        book.FilePath = $"/uploads/books/{fileName}";
        book.FileSizeBytes = file.Length;
        book.TotalPages = ExtractPageCount(filePath);
        book.UpdatedAt = DateTime.UtcNow;
        uow.Books.Update(book);
        await uow.SaveChangesAsync(ct);

        return Ok(new { filePath = book.FilePath, fileSizeBytes = book.FileSizeBytes, totalPages = book.TotalPages });
    }

    /// Reads the PDF's cross-reference table to get page count — no text extraction,
    /// so it's essentially instant even for large files.
    private static int ExtractPageCount(string filePath)
    {
        try
        {
            using var pdf = PdfDocument.Open(filePath);
            return pdf.NumberOfPages;
        }
        catch
        {
            // Malformed PDF or unsupported encryption — fall back to 0 rather than
            // failing the upload. The admin can re-upload if TotalPages is wrong.
            return 0;
        }
    }

    /// <summary>
    /// Validates that the uploaded file begins with the PDF magic bytes (%PDF = 25 50 44 46).
    /// Checking only the extension is insufficient — a renamed non-PDF would pass extension checks.
    /// </summary>
    private static async Task<bool> IsValidPdfAsync(IFormFile file)
    {
        var buffer = new byte[4];
        await using var stream = file.OpenReadStream();
        var read = await stream.ReadAsync(buffer.AsMemory(0, 4));
        return read == 4
            && buffer[0] == 0x25  // %
            && buffer[1] == 0x50  // P
            && buffer[2] == 0x44  // D
            && buffer[3] == 0x46; // F
    }

    /// <summary>
    /// Validates image magic bytes for JPEG (FF D8 FF), PNG (89 50 4E 47), and WebP (RIFF....WEBP).
    /// </summary>
    private static async Task<bool> IsValidImageAsync(IFormFile file)
    {
        var buffer = new byte[12];
        await using var stream = file.OpenReadStream();
        var read = await stream.ReadAsync(buffer.AsMemory(0, 12));
        if (read < 4) return false;

        // JPEG: FF D8 FF
        if (buffer[0] == 0xFF && buffer[1] == 0xD8 && buffer[2] == 0xFF)
            return true;

        // PNG: 89 50 4E 47
        if (buffer[0] == 0x89 && buffer[1] == 0x50 && buffer[2] == 0x4E && buffer[3] == 0x47)
            return true;

        // WebP: RIFF (52 49 46 46) at [0] and WEBP (57 45 42 50) at [8]
        if (read >= 12
            && buffer[0] == 0x52 && buffer[1] == 0x49 && buffer[2] == 0x46 && buffer[3] == 0x46
            && buffer[8] == 0x57 && buffer[9] == 0x45 && buffer[10] == 0x42 && buffer[11] == 0x50)
            return true;

        return false;
    }
}
