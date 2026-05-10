using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Bookmarks.Commands;

public record ExportBookmarksCommand(Guid UserId, Guid BookId) : IRequest<Result<string>>;

public class ExportBookmarksCommandHandler(
    IUnitOfWork uow,
    IEmailService emailService,
    UserManager<ApplicationUser> userManager
) : IRequestHandler<ExportBookmarksCommand, Result<string>>
{
    public async Task<Result<string>> Handle(ExportBookmarksCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByIdAsync(cmd.UserId.ToString());
        if (user is null) return Result<string>.Failure("User not found.");

        var book = await uow.Books.GetByIdAsync(cmd.BookId, ct);
        if (book is null) return Result<string>.Failure("Book not found.");

        var bookmarks = await uow.Bookmarks.Query()
            .Where(b => b.UserId == cmd.UserId && b.BookId == cmd.BookId && !b.IsDeleted)
            .OrderBy(b => b.PageNumber)
            .ToListAsync(ct);

        if (bookmarks.Count == 0)
            return Result<string>.Failure("No bookmarks found for this book.");

        var html = BuildHtml(book.Title, book.Author, user.UserName!, bookmarks);
        var subject = $"Your highlights from \"{book.Title}\" — Inkril";

        await emailService.SendAsync(user.Email!, subject, html, ct);

        return Result<string>.Success($"Your {bookmarks.Count} highlights have been emailed to {user.Email}.");
    }

    private static string BuildHtml(string title, string author, string userName, List<Bookmark> bookmarks)
    {
        var rows = bookmarks.Select(b =>
        {
            var highlight = !string.IsNullOrWhiteSpace(b.HighlightedText)
                ? $"""<blockquote style="margin:8px 0;padding:10px 16px;background:#FEF3C7;border-left:4px solid #F59E0B;border-radius:0 8px 8px 0;font-style:italic;color:#92400E">{System.Net.WebUtility.HtmlEncode(b.HighlightedText)}</blockquote>"""
                : "";

            var note = !string.IsNullOrWhiteSpace(b.Note)
                ? $"""<p style="margin:6px 0 0;color:#6B7280;font-size:13px">📝 {System.Net.WebUtility.HtmlEncode(b.Note)}</p>"""
                : "";

            return $"""
                <div style="margin-bottom:20px;padding:16px;background:#FAF5FF;border-radius:12px;border:1px solid #E9D5FF">
                  <p style="margin:0 0 6px;font-size:12px;font-weight:700;color:#6B21A8">Page {b.PageNumber}</p>
                  {highlight}
                  {note}
                </div>
                """;
        });

        return $"""
            <div style="font-family:sans-serif;max-width:600px;margin:auto;color:#1F2937">
              <div style="background:linear-gradient(135deg,#1A0A2E,#3B0764);padding:28px;border-radius:16px 16px 0 0;text-align:center">
                <h1 style="margin:0;color:white;font-size:22px">📚 Inkril — Your Highlights</h1>
              </div>
              <div style="padding:24px;background:white;border-radius:0 0 16px 16px;box-shadow:0 4px 16px rgba(107,33,168,.1)">
                <h2 style="margin:0 0 4px;color:#1F2937">{System.Net.WebUtility.HtmlEncode(title)}</h2>
                <p style="margin:0 0 20px;color:#6B7280">by {System.Net.WebUtility.HtmlEncode(author)}</p>
                <p style="color:#6B7280;font-size:14px">{bookmarks.Count} highlight{(bookmarks.Count == 1 ? "" : "s")} saved by {System.Net.WebUtility.HtmlEncode(userName)}</p>
                <hr style="border:none;border-top:2px solid #F3E8FF;margin:20px 0">
                {string.Join("\n", rows)}
                <p style="margin-top:24px;color:#9CA3AF;font-size:12px;text-align:center">
                  Exported from <strong>Inkril</strong> — your gamified reading companion.
                </p>
              </div>
            </div>
            """;
    }
}
