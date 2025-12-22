codeunit 50102 "Chiizu Invoices Processor"
{
    procedure MarkAsPaid(var VendLedgEntry: Record "Purch. Inv. Header")
    begin
        // Mock: set paid flag
        VendLedgEntry.Validate("Chiizu Paid", true);
        VendLedgEntry.Modify();
    end;
}
