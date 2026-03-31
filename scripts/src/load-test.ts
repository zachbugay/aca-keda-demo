import http from "k6/http";
import { check, sleep } from "k6";
import { Counter } from "k6/metrics";
import { Options } from "k6/options";
import { RefinedResponse, ResponseType } from "k6/http";

// -----------------------------------------------------------------------
// k6 load test for Azure Container Apps KEDA HTTP scaling demo
//
// Build:
//   cd scripts && npm install && npm run build
//
// Run:
//   k6 run -e TARGET_URL=https://<your-app-fqdn> scripts/dist/load-test.js
// -----------------------------------------------------------------------

interface ApiResponse {
  message: string;
  machineName: string;
  timestamp: string;
}

const replicaHits = new Counter("replica_hits");

export const options: Options = {
  stages: [
    { duration: "30s", target: 50 }, // ramp up to 50 virtual users
    { duration: "60s", target: 50 }, // hold at 50 VUs for 1 minute
    { duration: "30s", target: 0 },  // ramp down to 0
  ],
  thresholds: {
    http_req_duration: ["p(95)<2000"], // 95% of requests under 2s
    http_req_failed: ["rate<0.01"],    // <1% errors
  },
};

export default function (): void {
  const url = __ENV.TARGET_URL;
  if (!url) {
    throw new Error(
      "TARGET_URL environment variable is required. Run with: k6 run -e TARGET_URL=https://..."
    );
  }

  const res: RefinedResponse<ResponseType> = http.get(`${url}/`);

  check(res, {
    "status is 200": (r) => r.status === 200,
    "has machineName": (r) => {
      try {
        const body = JSON.parse(r.body as string) as ApiResponse;
        return body.machineName !== undefined;
      } catch {
        return false;
      }
    },
  });

  // Tag the metric with the replica machineName so the k6 summary
  // shows how requests were distributed across replicas
  try {
    const body = JSON.parse(res.body as string) as ApiResponse;
    replicaHits.add(1, { replica: body.machineName });
  } catch {
    // ignore parse errors
  }

  sleep(0.1); // small pause between requests
}
