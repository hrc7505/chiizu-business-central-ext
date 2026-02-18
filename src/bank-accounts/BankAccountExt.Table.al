tableextension 50105 "Chiizu Bank Account Ext" extends "Bank Account"
{
    fields
    {
        field(50100; "Chiizu Remote Balance"; Decimal)
        {
            Caption = 'Chiizu Remote Balance';
            Editable = false;
            DataClassification = CustomerContent;
        }
    }
}