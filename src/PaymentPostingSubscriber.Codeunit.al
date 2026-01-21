codeunit 50106 "Payment Posting Subscriber"
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
        StatusCalculator: Codeunit "Invoice Status Calculator";
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
