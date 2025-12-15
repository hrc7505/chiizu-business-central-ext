tableextension 50100 "Chiizu Vendor Ledger Ext" extends "Vendor Ledger Entry"
{
    fields
    {
        field(50100; "Chiizu Paid"; Boolean)
        {
            Caption = 'Chiizu Paid';
            DataClassification = CustomerContent;
        }
    }
}
