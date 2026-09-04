const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, ScanCommand, PutCommand, DeleteCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.DYNAMODB_TABLE;

exports.handler = async (event) => {
    // API Gateway HTTP API uses event.requestContext.http.method and event.rawPath
    const method = event.requestContext?.http?.method || event.httpMethod;
    const path = event.rawPath || event.path;

    // Handle CORS Preflight automatically if sent to Lambda
    if (method === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,Authorization",
                "Access-Control-Allow-Methods": "OPTIONS,GET,POST,DELETE"
            }
        };
    }

    const headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Credentials": true,
    };

    try {
        if (method === "GET" && path === "/clients") {
            const data = await docClient.send(new ScanCommand({ TableName: TABLE_NAME }));
            return {
                statusCode: 200,
                headers,
                body: JSON.stringify({ clients: data.Items || [] })
            };
        }

        if (method === "POST" && path === "/clients") {
            const body = JSON.parse(event.body);
            if (!body.publicKey || !body.clientName) {
                return { statusCode: 400, headers, body: JSON.stringify({ error: "Missing publicKey or clientName" }) };
            }

            // Generate Sequential IP
            const data = await docClient.send(new ScanCommand({ TableName: TABLE_NAME }));
            let maxIpVal = 99; // Base IP starts at 10.8.0.100
            for (const item of data.Items || []) {
                if (item.ClientIp) {
                    const lastOctet = parseInt(item.ClientIp.split('.').pop());
                    if (lastOctet > maxIpVal) {
                        maxIpVal = lastOctet;
                    }
                }
            }
            const nextIp = `10.8.0.${maxIpVal + 1}`;

            const item = {
                PublicKey: body.publicKey,
                ClientName: body.clientName,
                ClientIp: nextIp,
                CreatedAt: new Date().toISOString()
            };

            await docClient.send(new PutCommand({
                TableName: TABLE_NAME,
                Item: item
            }));

            return {
                statusCode: 200,
                headers,
                body: JSON.stringify(item)
            };
        }

        if (method === "DELETE" && path.startsWith("/clients/")) {
            const pubKey = decodeURIComponent(path.split("/clients/")[1]);
            await docClient.send(new DeleteCommand({
                TableName: TABLE_NAME,
                Key: { PublicKey: pubKey }
            }));
            return {
                statusCode: 200,
                headers,
                body: JSON.stringify({ success: true })
            };
        }

        return { statusCode: 404, headers, body: "Not Found" };
    } catch (err) {
        console.error(err);
        return { statusCode: 500, headers, body: JSON.stringify({ error: err.message }) };
    }
};
