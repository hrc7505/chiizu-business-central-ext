codeunit 50140 "Chiizu Webhook Receiver"
{
    procedure HandleWebhook(
        BatchId: Code[50];
        Status: Enum "Chiizu Payment Status";
        PaymentRef: Code[50];
        IncomingSecret: Text)
    var
        Setup: Record "Chiizu Setup";
        WebhookRec: Record "Chiizu Payment Webhook";
        Processor: Codeunit "Chiizu Payment Processor";
    begin
        // ✅ VERIFIER GOES HERE
        Setup.Get();
        if IncomingSecret <> Setup."Webhook Secret" then
            Error('Invalid webhook');

        // Save webhook
        WebhookRec.Init();
        WebhookRec."Batch Id" := BatchId;
        WebhookRec.Status := Status;
        WebhookRec."Payment Reference" := PaymentRef;
        WebhookRec."Received At" := CurrentDateTime();
        WebhookRec.Insert(true);

        // Call processor
        Processor.Run(WebhookRec);
    end;
}
