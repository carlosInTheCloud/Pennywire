// Values come from the Terraform outputs of the vpn_server module and are injected at
// build time from a local .env file (see .env.example), so nothing account-specific
// is committed here. Vite only substitutes statically written import.meta.env.VITE_*
// references, so keep these accesses inline.
const awsExports = {
  aws_project_region: import.meta.env.VITE_AWS_REGION,
  aws_cognito_region: import.meta.env.VITE_AWS_REGION,
  aws_user_pools_id: import.meta.env.VITE_COGNITO_USER_POOL_ID,
  aws_user_pools_web_client_id: import.meta.env.VITE_COGNITO_CLIENT_ID,
  api_endpoint: import.meta.env.VITE_API_ENDPOINT
};

const missing = Object.entries(awsExports)
  .filter(([, value]) => !value)
  .map(([key]) => key);

if (missing.length > 0) {
  throw new Error(
    `Missing webapp configuration: ${missing.join(', ')}. Copy .env.example to .env and fill it in from "terraform output".`
  );
}

export default awsExports;
