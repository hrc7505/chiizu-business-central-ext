namespace Chiizu;

page 1000040 "Chiizu Payment Webhook API"
{
    PageType = API;
    SourceTable = "Chiizu Payment Webhook";
    DelayedInsert = true;
    ODataKeyFields = SystemId;

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
                field(id; Rec.SystemId) { }
                field(batchId; Rec."Batch Id") { }
                field(status; Rec.Status) { }
                field(paymentReference; Rec."Payment Reference") { }
                field(bankAccountNo; Rec."Bank Account No.") { }
            }
        }
    }
}
