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
                    Caption = 'Total Amount to Pay';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
            }

            group(PayFromBankAccount)
            {
                Caption = 'Bank Account Details';

                field(BankAccountNo; BankAccountNo)
                {
                    Caption = 'Bank Account No.';
                    ApplicationArea = All;
                    TableRelation = "Bank Account"."No.";

                    trigger OnValidate()
                    var
                        BankAcc: Record "Bank Account";
                    begin
                        Clear(BankAccountName);
                        BankAccountRemoteBalance := 0;
                        BankAccountBCBalance := 0;

                        if BankAccountNo <> '' then begin
                            if BankAcc.Get(BankAccountNo) then begin
                                BankAccountName := BankAcc.Name;
                                // 1. Fetch Remote Balance (Extension Field)
                                BankAccountRemoteBalance := BankAcc."Chiizu Remote Balance";

                                // 2. Calculate and fetch standard BC Ledger Balance (FlowField)
                                BankAcc.CalcFields(Balance);
                                BankAccountBCBalance := BankAcc.Balance;
                            end;
                        end;
                        UpdateBalanceStyle();
                    end;
                }

                field(BankAccountName; BankAccountName)
                {
                    Caption = 'Account Name';
                    ApplicationArea = All;
                    Editable = false;
                }

                field(BankAccountRemoteBalance; BankAccountRemoteBalance)
                {
                    Caption = 'Chiizu Remote Balance';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = RemoteBalanceStyle;
                    ToolTip = 'Red if balance is less than the total payment amount.';
                    Visible = false; // Hiding as per latest decision, can be toggled on if needed
                }

                field(BankAccountBCBalance; BankAccountBCBalance)
                {
                    Caption = 'BC Ledger Balance';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = BCBalanceStyle;
                    ToolTip = 'Red if ledger balance is less than the total payment amount.';
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

            group(InvoicesGroup)
            {
                Caption = 'Invoices to Pay';

                part(Invoices; "Chiizu Finalize Invoice List")
                {
                    ApplicationArea = All;
                    UpdatePropagation = Both;
                }
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
                    // Sync the list variable with the current subpage view
                    CurrPage.Invoices.Page.GetRemainingInvoiceNos(InvoiceNos);

                    if InvoiceNos.Count() = 0 then
                        Error('No invoices left to pay.');

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

                    PaymentService.ScheduleInvoicesFromFinalize(InvoiceNos, BankAccountNo, ScheduledDate);
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
        BankAccountRemoteBalance: Decimal;
        BankAccountBCBalance: Decimal;
        TotalAmount: Decimal;
        ScheduledDate: Date;
        FinalizeMode: Enum "Chiizu Finalize Mode";
        RemoteBalanceStyle: Text;
        BCBalanceStyle: Text;

    procedure SetContext(Invoices: List of [Code[20]]; Mode: Enum "Chiizu Finalize Mode")
    begin
        InvoiceNos := Invoices;
        FinalizeMode := Mode;
        if FinalizeMode = FinalizeMode::Schedule then ScheduledDate := Today;
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
        UpdateBalanceStyle();
    end;

    local procedure UpdateBalanceStyle()
    begin
        // Logic: Turn Red if Balance is less than the Total Amount we want to pay
        // Remote Balance Style
        if (BankAccountRemoteBalance < TotalAmount) then
            RemoteBalanceStyle := 'Unfavorable'
        else
            RemoteBalanceStyle := 'Favorable';

        // BC Ledger Balance Style
        if (BankAccountBCBalance < TotalAmount) then
            BCBalanceStyle := 'Unfavorable'
        else
            BCBalanceStyle := 'Favorable';
    end;

    trigger OnOpenPage()
    begin
        // Push selected invoices into subpage AFTER page is created
        CurrPage.Invoices.Page.SetInvoices(InvoiceNos);
    end;

    trigger OnAfterGetCurrRecord()
    begin
        // IMPORTANT: Pull the current list FROM the subpage buffer
        CurrPage.Invoices.Page.GetRemainingInvoiceNos(InvoiceNos);
        CalculateTotal();
    end;
}