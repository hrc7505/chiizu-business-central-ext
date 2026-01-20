tableextension 50100 "Chiizu Purchase Invoices Ext" extends "Purch. Inv. Header"
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
