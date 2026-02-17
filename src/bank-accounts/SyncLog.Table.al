table 50107 "Chiizu Sync Log"
{
    DataClassification = CustomerContent;
    Caption = 'Chiizu Sync Log';
    LookupPageId = "Chiizu Sync Log";
    DrillDownPageId = "Chiizu Sync Log";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
            Caption = 'Entry No.';
        }
        field(2; "Sync DateTime"; DateTime)
        {
            Caption = 'Sync DateTime';
        }
        field(3; Status; Option)
        {
            OptionMembers = Success,Error;
            Caption = 'Status';
        }
        field(4; "Message"; Text[250])
        {
            Caption = 'Message';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}