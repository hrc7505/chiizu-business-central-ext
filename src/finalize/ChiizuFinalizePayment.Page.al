namespace Chiizu.Finalize;
using Chiizu;
using Microsoft.Bank.BankAccount;
using Microsoft.Purchases.Payables;

page 1000007 "Chiizu Finalize Payment"
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
                    ToolTip = 'Displays the total amount of all invoices to be paid.';
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
                    ToolTip = 'Select the bank account from which the payment will be made.';
                    ApplicationArea = All;
                    TableRelation = "Bank Account"."No.";

                    trigger OnValidate()
                    var
                        BankAcc: Record "Bank Account";
                    begin
                        Clear(BankAccountName);

                        if BankAccountNo <> '' then
                            if BankAcc.Get(BankAccountNo) then
                                BankAccountName := BankAcc.Name
                            else
                                Error('Bank account not found: %1', BankAccountNo);
                    end;
                }

                field(BankAccountName; BankAccountName)
                {
                    Caption = 'Bank Account Name';
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the name of the selected bank account.';
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
                    ToolTip = 'Specifies the date when the payment is scheduled to be processed.';

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
                PromotedOnly = true;
                ToolTip = 'Confirm and initiate the payment for the selected invoices immediately.';
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
                PromotedOnly = true;
                ToolTip = 'Confirm and schedule the payment for the selected invoices on the specified date.';
                Visible = FinalizeMode = FinalizeMode::Schedule;

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                begin
                    // Sync the list variable with the current subpage view
                    CurrPage.Invoices.Page.GetRemainingInvoiceNos(InvoiceNos);

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

    procedure SetContext(SourceInvoices: List of [Code[20]]; Mode: Enum "Chiizu Finalize Mode")
    begin
        InvoiceNos := SourceInvoices;
        FinalizeMode := Mode;

        if FinalizeMode = FinalizeMode::Schedule then
            ScheduledDate := Today;

        this.CalculateTotal();
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

    // Update this trigger in the parent page (1000007)
    trigger OnAfterGetCurrRecord()
    begin
        // IMPORTANT: Pull the current list FROM the subpage buffer
        CurrPage.Invoices.Page.GetRemainingInvoiceNos(InvoiceNos);
        this.CalculateTotal();
    end;
}
