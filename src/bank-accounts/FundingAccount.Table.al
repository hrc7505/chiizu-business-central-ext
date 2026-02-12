table 50105 "Chiizu Funding Account"
{
    DataClassification = CustomerContent;
    Caption = 'Chiizu Funding Account';

    fields
    {
        field(1; "Account Id"; Code[50]) { Caption = 'Account ID'; }
        field(2; Name; Text[100]) { Caption = 'Account Name'; }
        field(3; "Account Number"; Text[30]) { Caption = 'Account Number'; }
        field(4; "Account Type"; Text[30]) { Caption = 'Type'; }
        field(5; "Currency Code"; Code[10]) { Caption = 'Currency'; }
    }

    keys
    {
        key(PK; "Account Id") { Clustered = true; }
    }
}