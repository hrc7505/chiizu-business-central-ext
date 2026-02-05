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
                    Caption = 'Bank Account';
                    ApplicationArea = All;
                    TableRelation = "Bank Account"."No.";

                    trigger OnValidate()
                    var
                        BankAcc: Record "Bank Account";
                    begin
                        Clear(BankAccountName);

                        if BankAccountNo <> '' then begin
                            if BankAcc.Get(BankAccountNo) then
                                BankAccountName := BankAcc.Name
                            else
                                Error('Bank account not found: %1', BankAccountNo);
                        end;
                    end;
                }

                field(BankAccountName; BankAccountName)
                {
                    Caption = 'Bank Account Name';
                    ApplicationArea = All;
                    Editable = false;
                }
            }

            part(Invoices; "Chiizu Finalize Invoice List")
            {
                Caption = 'Invoices to Pay';
                ApplicationArea = All;
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
                    if BankAccountNo = '' then
                        Error('Please select a bank account before proceeding.');

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

    procedure SetContext(Invoices: List of [Code[20]])
    begin
        InvoiceNos := Invoices;
        CalculateTotal();
    end;

    local procedure CalculateTotal()
    var
        VLE: Record "Vendor Ledger Entry";
        i: Integer;
    begin
        TotalAmount := 0;

        for i := 1 to InvoiceNos.Count() do begin
            VLE.SetRange("Document No.", InvoiceNos.Get(i));
            VLE.SetRange(Open, true);
            if VLE.FindFirst() then begin
                VLE.CalcFields("Remaining Amount");
                TotalAmount += Abs(VLE."Remaining Amount");
            end;
        end;
    end;

    trigger OnOpenPage()
    begin
        // Push selected invoices into subpage AFTER page is created
        CurrPage.Invoices.Page.SetInvoices(InvoiceNos);
    end;
}
