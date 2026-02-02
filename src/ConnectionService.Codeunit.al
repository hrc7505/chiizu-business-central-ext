codeunit 50120 "Chiizu Connection Service"
{
    procedure TestConnection(BaseUrl: Text; ApiKey: Text)
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
    begin
        Request.SetRequestUri(BaseUrl + '/health');
        Request.Method := 'GET';

        Request.GetHeaders(Headers);
        Headers.Add('Authorization', 'Bearer ' + ApiKey);

        Client.Send(Request, Response);

        if not Response.IsSuccessStatusCode() then
            Error(
                'Failed to connect to Chiizu. Status code: %1',
                Response.HttpStatusCode()
            );
    end;
}
