page 50140 "Chiizu Payment Webhook API"
{
    PageType = API;
    SourceTable = "Chiizu Payment Webhook";
    DelayedInsert = true;

    APIPublisher = 'chiizu';
    APIGroup = 'payments';
    APIVersion = 'v1.0';
    EntityName = 'paymentWebhook';
    EntitySetName = 'paymentWebhooks';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(batchId; Rec."Batch Id") { }
                field(status; Rec.Status) { }
                field(paymentReference; Rec."Payment Reference") { }
            }
        }
    }
}
