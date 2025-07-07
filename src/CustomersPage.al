
page 50100 CustomersPage
{
    Caption = 'Customers BY CHIIZU';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = Customer;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            usercontrol(CustomerControl; CustomersControlAddIn)
            {
                ApplicationArea = All;

                trigger OnJsReady()
                var
                    CustomerRec: Record Customer;
                    CustomerArray: JsonArray;
                    CustomerObj: JsonObject;
                    JsonText: Text;
                begin
                    if HasInitialized then
                        exit;

                    HasInitialized := true;

                    CustomerRec.Reset();
                    if CustomerRec.FindSet() then begin
                        repeat
                            Clear(CustomerObj);
                            CustomerObj.Add('Name', CustomerRec.Name);
                            CustomerObj.Add('No', CustomerRec."No.");
                            CustomerArray.Add(CustomerObj);
                        until CustomerRec.Next() = 0;
                    end;

                    CustomerArray.WriteTo(JsonText);
                    CurrPage.CustomerControl.DisplayList('Customers', JsonText);
                end;

            }
        }
    }

    var
        JsonText: Text;
        HasInitialized: Boolean;
}
