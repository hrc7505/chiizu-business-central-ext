namespace Chiizu;

using Microsoft.Purchases.Payables;

codeunit 1000006 "Chiizu Payment Posting Subscr"
{
    [EventSubscriber(
        ObjectType::Table,
        Database::"Vendor Ledger Entry",
        'OnAfterModifyEvent',
        '',
        false,
        false
    )]
    local procedure OnAfterModifyVendorLedger(
        var Rec: Record "Vendor Ledger Entry";
        var xRec: Record "Vendor Ledger Entry"
    )
    var
        StatusCalculator: Codeunit "Chiizu Invoice Status Calc";
    begin
        // Only invoices
        if Rec."Document Type" <> Rec."Document Type"::Invoice then
            exit;

        // Only if remaining amount changed
        if Rec."Remaining Amount" = xRec."Remaining Amount" then
            exit;

        StatusCalculator.RecalculateFromVendorLedger(Rec);
    end;
}
