codeunit 50102 "Chiizu Payment Processor"
{
    procedure MarkAsPaid(var VendLedgEntry: Record "Vendor Ledger Entry")
    begin
        // Mock: set paid flag
        VendLedgEntry.Validate("Chiizu Paid", true);
        VendLedgEntry.Modify();
    end;
}
