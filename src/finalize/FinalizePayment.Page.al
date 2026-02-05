page 50107 "Chiizu Finalize Payment"
{
    PageType = Card;
    ApplicationArea = All;
    Caption = 'Finalize Chiizu Payment';
    UsageCategory = None;

    layout
    {
        area(content)
        {
            group(Summary)
            {
                Caption = 'Payment Summary';

                field(TotalAmount; TotalAmount)
                {
                    Caption = 'Total Amount';
                    ApplicationArea = All;
                    Editable = false;
                }
            }

            group(PayFromBankAccount)
            {
                Caption = 'Pay From Bank Account';

                field(BankAccountNo; BankAccountNo)
                {
                    Caption = 'Bank Account No.';
                    ApplicationArea = All;
                    Editable = false;
                }

                field(BankAccountName; BankAccountName)
                {
                    Caption = 'Bank Account Name';
                    ApplicationArea = All;
                    Editable = false;
                }
            }

            group(InvoicesGroup)
            {
                Caption = 'Invoices to Pay';


                part(Invoices; "Chiizu Finalize Invoice List")
                {
                    ApplicationArea = All;
                }
            }

        }
    }

    actions
    {
        area(processing)
        {
            action(ConfirmPayment)
            {
                Caption = 'Confirm & Pay';
                Image = Payment;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                begin
                    PaymentService.PayInvoices(InvoiceNos, BankAccountNo);
                    Message('%1 invoice(s) sent to Chiizu for processing.', InvoiceNos.Count());
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        InvoiceNos: List of [Code[20]];
        BankAccountNo: Code[20];
        TotalAmount: Decimal;
        BankAccountName: Text[100];

    trigger OnOpenPage()
    begin
        CurrPage.Invoices.Page.SetInvoices(InvoiceNos);
        TotalAmount := CurrPage.Invoices.Page.GetTotalAmount();
    end;


    trigger OnAfterGetCurrRecord()
    begin
        TotalAmount := CurrPage.Invoices.Page.GetTotalAmount();
    end;

    procedure SetContext(Invoices: List of [Code[20]]; BankAccNo: Code[20]; BankAccName: Text[100])
    begin
        InvoiceNos := Invoices;
        BankAccountNo := BankAccNo;
        BankAccountName := BankAccName;
    end;

    procedure RefreshTotalFromInvoices()
    begin
        TotalAmount := CurrPage.Invoices.Page.GetTotalAmount();
        CurrPage.Update(false);
    end;

}
