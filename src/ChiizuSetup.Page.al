page 50103 "Chiizu Setup"
{
    PageType = Card;
    SourceTable = "Chiizu Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Chiizu Setup';

    layout
    {
        area(content)
        {
            group(General)
            {
                field("API Base URL"; Rec."API Base URL") { }
            }

            group(Webhook)
            {
                field("Webhook Secret"; Rec."Webhook Secret") { }
            }

            group(PaymentJournal)
            {
                field("Payment Jnl. Template"; Rec."Payment Jnl. Template")
                {
                    Caption = 'Payment Journal Template';
                    ToolTip = 'Specifies the payment journal template to be used for Chiizu payments.';
                }

                field("Payment Jnl. Batch"; Rec."Payment Jnl. Batch")
                {
                    Caption = 'Payment Journal Batch';
                    ToolTip = 'Specifies the payment journal batch to be used for Chiizu payments.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Rec.Get('CHIIZU') then begin
            Rec.Init();
            Rec."Primary Key" := 'CHIIZU';
            Rec.Insert();
        end;
    end;
}
