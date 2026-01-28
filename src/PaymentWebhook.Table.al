table 50149 "Chiizu Payment Webhook"
{
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer) { AutoIncrement = true; }
        field(2; "Batch Id"; Code[20]) { }
        field(3; Status; Enum "Chiizu Payment Status") { }
        field(4; "Payment Reference"; Code[50]) { }
        field(5; "Received At"; DateTime) { }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
    }

    trigger OnInsert()
    var
        Processor: Codeunit "Chiizu Payment Processor";
        RecCopy: Record "Chiizu Payment Webhook";
    begin
        "Received At" := CurrentDateTime();

        RecCopy := Rec;
        Processor.Run(RecCopy); // ✅ correct
    end;
}
