codeunit 50107 "Invoice Status Calculator"
{
    procedure RecalculateFromVendorLedger(VLE: Record "Vendor Ledger Entry")
    var
        InvoiceStatus: Record "Chiizu Invoice Status";
        NewStatus: Enum "Chiizu Payment Status";
    begin
        if not InvoiceStatus.Get(VLE."Document No.") then
            exit;

        VLE.CalcFields("Remaining Amount");

        if VLE."Remaining Amount" = 0 then
            NewStatus := NewStatus::Paid
        else
            NewStatus := NewStatus::"Partially Paid";

        InvoiceStatus.SetStatusSystem(NewStatus, InvoiceStatus."Scheduled Date");
    end;

    procedure ResolveFromBC(VLE: Record "Vendor Ledger Entry"): Enum "Chiizu Payment Status"
    begin
        VLE.CalcFields("Remaining Amount");

        if VLE."Remaining Amount" = 0 then
            exit("Chiizu Payment Status"::Paid);

        if VLE."Remaining Amount" < VLE.Amount then
            exit("Chiizu Payment Status"::"Partially Paid");

        exit("Chiizu Payment Status"::Open);
    end;

}
