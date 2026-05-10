using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Inkril.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddYearlyBookGoal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "YearlyBookGoal",
                table: "UserSettings",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "YearlyBookGoal",
                table: "UserSettings");
        }
    }
}
