table 50149 "Chiizu Payment Webhook"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
        }

        field(2; "Batch Id"; Code[50]) { }

        field(3; Status; Enum "Chiizu Payment Status") { }

        field(4; "Payment Reference"; Code[50]) { }

        field(5; "Received At"; DateTime) { }

        field(40; "Webhook Secret"; Text[100]) { }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        "Received At" := CurrentDateTime();
        Codeunit.Run(Codeunit::"Chiizu Payment Processor", Rec);
    end;
}
