codeunit 50120 "Chiizu Payment Status Mgt"
{
    procedure ResolveFromBC(
        VendorLedgEntry: Record "Vendor Ledger Entry"
    ): Enum "Chiizu Payment Status"
    begin
        // Fully paid
        if VendorLedgEntry."Remaining Amount" = 0 then
            exit("Chiizu Payment Status"::Paid);

        // Partially paid
        if VendorLedgEntry."Remaining Amount" < VendorLedgEntry.Amount then
            exit("Chiizu Payment Status"::"Partially Paid");

        // No payment applied
        exit("Chiizu Payment Status"::Open);
    end;
}
