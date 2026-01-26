page 50140 "Chiizu Payment Webhook API"
{
    PageType = API;
    SourceTable = "Chiizu Payment Webhook";

    APIPublisher = 'chiizu';
    APIGroup = 'payments';
    APIVersion = 'v1.0';
    EntityName = 'webhook';
    EntitySetName = 'webhooks';

    DelayedInsert = true;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(batchId; Rec."Batch Id") { }
                field(invoiceNo; Rec."Invoice No.") { }
                field(paymentIntentId; Rec."Payment Intent Id") { }
                field(paymentReference; Rec."Payment Reference") { }
                field(status; Rec.Status) { }
                field(signature; Rec.Signature) { }
                field(payload; Rec.Payload) { }
            }
        }
    }
}
