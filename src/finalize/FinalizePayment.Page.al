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

            group(ScheduleInfo)
            {
                Caption = 'Schedule Payment';
                Visible = FinalizeMode = FinalizeMode::Schedule;

                field(ScheduledDate; ScheduledDate)
                {
                    Caption = 'Scheduled Date';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        if ScheduledDate < Today then
                            Error('Scheduled date must be today or later.');
                    end;
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
            action(ConfirmPay)
            {
                Caption = 'Confirm & Pay';
                Image = Payment;
                Promoted = true;
                PromotedCategory = Process;
                Visible = FinalizeMode = FinalizeMode::Pay;

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                begin
                    if BankAccountNo = '' then
                        Error('Please select a bank account.');

                    PaymentService.PayInvoices(InvoiceNos, BankAccountNo);

                    Message('%1 invoice(s) sent for payment.', InvoiceNos.Count());
                    CurrPage.Close();
                end;
            }

            action(ConfirmSchedule)
            {
                Caption = 'Confirm & Schedule';
                Image = Calendar;
                Promoted = true;
                PromotedCategory = Process;
                Visible = FinalizeMode = FinalizeMode::Schedule;

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                begin
                    if BankAccountNo = '' then
                        Error('Please select a bank account.');

                    if ScheduledDate = 0D then
                        Error('Please select a scheduled date.');

                    PaymentService.ScheduleInvoicesFromFinalize(
                        InvoiceNos,
                        BankAccountNo,
                        ScheduledDate
                    );

                    Message('%1 invoice(s) scheduled successfully.', InvoiceNos.Count());
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        InvoiceNos: List of [Code[20]];
        BankAccountNo: Code[20];
        BankAccountName: Text[100];
        TotalAmount: Decimal;
        ScheduledDate: Date;
        FinalizeMode: Enum "Chiizu Finalize Mode";

    procedure SetContext(Invoices: List of [Code[20]]; Mode: Enum "Chiizu Finalize Mode")
    begin
        InvoiceNos := Invoices;
        FinalizeMode := Mode;

        if FinalizeMode = FinalizeMode::Schedule then
            ScheduledDate := Today;

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
