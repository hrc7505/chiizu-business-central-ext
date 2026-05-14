namespace Chiizu;

table 1000049 "Chiizu Payment Webhook"
{
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer) { AutoIncrement = true; }
        field(2; "Batch Id"; Code[50]) { }
        field(3; Status; Enum "Chiizu Payment Status") { }
        field(4; "Payment Reference"; Code[50]) { }
        field(5; "Received At"; DateTime) { }
        field(6; "Bank Account No."; Code[20]) { }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
    }

    trigger OnInsert()
    var
        RecCopy: Record "Chiizu Payment Webhook";
        Processor: Codeunit "Chiizu Payment Processor";
    begin
        "Received At" := CurrentDateTime();

        RecCopy := Rec;
        Processor.Run(RecCopy); // ✅ correct
    end;
}
