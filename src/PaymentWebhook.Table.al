table 50149 "Chiizu Payment Webhook"
{
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
        }

        field(2; "Batch Id"; Code[50]) { }
        field(3; "Invoice No."; Code[20]) { }
        field(4; "Payment Intent Id"; Code[50]) { }
        field(5; "Payment Reference"; Code[50]) { }

        field(6; Status; Enum "Chiizu Payment Status") { }

        // 🔐 Provided by gateway (HMAC / signature)
        field(7; "Signature"; Text[250]) { }

        // 🔍 Audit
        field(8; "Received At"; DateTime) { }
        field(9; Payload; Text[2048]) { }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
    }

    trigger OnInsert()
    var
        Verifier: Codeunit "Chiizu Webhook Verifier";
        Processor: Codeunit "Chiizu Payment Processor";
        RecCopy: Record "Chiizu Payment Webhook";
    begin
        Message(
        '🔥 WEBHOOK RECEIVED 🔥\Batch=%1 Status=%2',
        "Batch Id",
        Status
    );
        "Received At" := CurrentDateTime();

        RecCopy := Rec;                    // Safety copy
        Processor.Run(RecCopy);            // Business logic
    end;
}
