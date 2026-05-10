using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Books.Commands;
using Inkril.Application.Features.Books.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using UglyToad.PdfPig;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class BooksController(IMediator mediator, ICurrentUserService currentUser, IUnitOfWork uow, IWebHostEnvironment env) : ControllerBase
{
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetAll([FromQuery] GetBooksQuery query, CancellationToken ct)
        => Ok(await mediator.Send(query, ct));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new GetBookByIdQuery(id, currentUser.UserId), ct);
        return result.Succeeded ? Ok(result.Value) : NotFound(new { message = result.Errors[0] });
    }

    [HttpPost]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> Create([FromBody] CreateBookCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        return result.Succeeded
            ? CreatedAtAction(nameof(GetById), new { id = result.Value }, new { id = result.Value })
            : BadRequest(new { errors = result.Errors });
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateBookCommand cmd, CancellationToken ct)
    {
        if (id != cmd.Id) return BadRequest("Route ID and body ID do not match.");
        var result = await mediator.Send(cmd, ct);
        return result.Succeeded ? NoContent() : BadRequest(new { errors = result.Errors });
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
    [Authorize(Roles = "desktop")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<IActionResult> UploadCover(Guid id, IFormFile file, CancellationToken ct)
    {
        if (file.Length == 0) return BadRequest(new { errors = new[] { "No file provided." } });

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp"))
            return BadRequest(new { errors = new[] { "Only JPG, PNG and WebP are accepted for cover images." } });

        var book = await uow.Books.GetByIdAsync(id, ct);
        if (book is null) return NotFound();

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
    [Authorize(Roles = "desktop")]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<IActionResult> UploadPdf(Guid id, IFormFile file, CancellationToken ct)
    {
        if (file.Length == 0) return BadRequest(new { errors = new[] { "No file provided." } });

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext != ".pdf")
            return BadRequest(new { errors = new[] { "Only PDF files are accepted." } });

        var book = await uow.Books.GetByIdAsync(id, ct);
        if (book is null) return NotFound();

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
}
