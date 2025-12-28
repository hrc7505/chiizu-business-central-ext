pageextension 50103 "Chiizu Purch Invoice Card Ext" extends "Purchase Invoice"
{
    layout
    {
        addlast(General)
        {
            field("Chiizu Paid"; IsChiizuPaid())
            {
                ApplicationArea = All;
                Editable = false;
            }
        }
    }

    local procedure IsChiizuPaid(): Boolean
    var
        Status: Record "Chiizu Invoice Status";
    begin
        if Status.Get(Rec."No.") then
            exit(Status."Paid via Chiizu");

        exit(false);
    end;
}
