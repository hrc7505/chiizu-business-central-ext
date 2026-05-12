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

        field(50101; "Account Verified"; Boolean)
        {
            Caption = 'Account Verified';
            DataClassification = CustomerContent;
            Editable = false; // Users can't just check this manually; logic must do it.
        }
    }
}