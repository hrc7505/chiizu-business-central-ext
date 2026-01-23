codeunit 50139 "Chiizu Url Helper"
{
    procedure GetPaymentWebhookUrl(): Text
    begin
        exit(
            GetUrl(
                ClientType::Api,
                CompanyName,
                ObjectType::Page,
                Page::"Chiizu Payment Webhook API"
            )
        );
    end;
}
