using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Inkril.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddIsLocalToBooks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsLocal",
                table: "Books",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsLocal",
                table: "Books");
        }
    }
}
