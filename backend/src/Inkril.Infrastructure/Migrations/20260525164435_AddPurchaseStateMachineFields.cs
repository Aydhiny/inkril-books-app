using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Inkril.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPurchaseStateMachineFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Purchases",
                type: "character varying(25)",
                maxLength: 25,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(20)",
                oldMaxLength: 20);

            migrationBuilder.AddColumn<long>(
                name: "RefundedAmountCents",
                table: "Purchases",
                type: "bigint",
                nullable: false,
                defaultValue: 0L);

            migrationBuilder.AddColumn<string>(
                name: "StripeRefundId",
                table: "Purchases",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RefundedAmountCents",
                table: "Purchases");

            migrationBuilder.DropColumn(
                name: "StripeRefundId",
                table: "Purchases");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Purchases",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(25)",
                oldMaxLength: 25);
        }
    }
}
