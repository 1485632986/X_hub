import http from "@ohos:net.http";
/**
 * HTTP response wrapper
 */
export interface HttpResponse {
    statusCode: number;
    data: string;
}
/**
 * Simple HTTP client wrapping @ohos.net.http
 */
export class HttpClient {
    /**
     * Send an HTTP request
     */
    static async request(url: string, method: http.RequestMethod, header: Record<string, string> = {}, body?: string): Promise<HttpResponse> {
        const httpRequest = http.createHttp();
        try {
            const options: http.HttpRequestOptions = {
                method: method,
                header: header,
                connectTimeout: 10000,
                readTimeout: 30000,
                extraData: body
            };
            const response = await httpRequest.request(url, options);
            return {
                statusCode: response.responseCode,
                data: response.result as string
            };
        }
        finally {
            httpRequest.destroy();
        }
    }
    /**
     * GET request
     */
    static async get(url: string, header: Record<string, string> = {}): Promise<HttpResponse> {
        return HttpClient.request(url, http.RequestMethod.GET, header);
    }
    /**
     * POST request with JSON body
     */
    static async post(url: string, body: object, header: Record<string, string> = {}): Promise<HttpResponse> {
        const headers: Record<string, string> = {};
        headers['Content-Type'] = 'application/json';
        const keys: string[] = Object.keys(header);
        for (let i = 0; i < keys.length; i++) {
            headers[keys[i]] = header[keys[i]];
        }
        return HttpClient.request(url, http.RequestMethod.POST, headers, JSON.stringify(body));
    }
}
