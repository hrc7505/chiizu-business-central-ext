table 50143 "Chiizu Payment Webhook Log"
{
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Batch Id"; Code[50]) { }
        field(2; Status; Enum "Chiizu Payment Status") { }
        field(3; "Payment Reference"; Code[50]) { }
        field(4; "Received At"; DateTime) { }
    }

    keys
    {
        key(PK; "Batch Id", Status, "Payment Reference") { Clustered = true; }
    }
}
