**Project Overview**

- **Name:** DevOps demo — React frontend + Node backend + MySQL
- **Description:** A full-stack sample application packaged with Docker Compose and an opinionated monitoring stack (Prometheus, Grafana, Alertmanager). This repository demonstrates how to containerize an app, export metrics, monitor services, and send alerts when a service becomes unavailable.

**Repository Structure**

- **File:** [docker-compose.yml](docker-compose.yml) : Primary application compose file (mysql, backend, frontend, nginx)
- **File:** [docker-compose-monitor.yml](docker-compose-monitor.yml) : Compose for Prometheus, Grafana, exporters, and Alertmanager
- **Folder:** [backend](backend) : Node.js backend (exposes /metrics)
- **Folder:** [frontend](frontend) : React frontend
- **Folder:** [monitoring/prometheus](monitoring/prometheus) : Prometheus config and alert rules
- **Folder:** [monitoring/alertmanager](monitoring/alertmanager) : Alertmanager config
- **Folder:** [monitoring/grafana](monitoring/grafana) : Grafana provisioning and dashboards
- **Folder:** [mysql-init](mysql-init) : Example DB init SQL
- **Folder:** [nginx](nginx) : Nginx configuration
- **File:** [deploy/backend_deploy_bluegreen.sh](deploy/backend_deploy_bluegreen.sh) : Deployment helper scripts

Prerequisites

- Docker Engine and Docker Compose installed on the target server (EC2). For macOS development use Docker Desktop.
- Recommended: At least 2 vCPU and 4GB RAM for running app + monitoring locally on a small VM.
- Optional: An Alertmanager receiver (Slack webhook or SMTP credentials) for notifications.

Quick start (single-server)

1) Clone the repository:

```bash
git clone <repo-url>
cd devops-project-react-node-mysql
```

2) Create the external Docker network used by the monitor compose (the monitor compose expects an existing `devops` network):

```bash
docker network create devops
```

3) Start the main application stack (application services):

```bash
docker compose up -d
```

4) Start the monitoring stack (Prometheus, Grafana, exporters, Alertmanager):

```bash
docker compose -f docker-compose-monitor.yml up -d
```

5) Open the UIs in your browser (replace SERVER_IP as appropriate):

- Prometheus: http://SERVER_IP:9090
- Grafana: http://SERVER_IP:3000  (user: admin / password from compose)
- Alertmanager: http://SERVER_IP:9093

Prometheus config and alert rules

- Prometheus reads its main config from [monitoring/prometheus/prometheus.yml](monitoring/prometheus/prometheus.yml). Alert rule groups are defined in [monitoring/prometheus/alert-rules.yml](monitoring/prometheus/alert-rules.yml).
- Ensure `alert-rules.yml` is mounted into the Prometheus container; this repository's `docker-compose-monitor.yml` mounts it to `/etc/prometheus/alert-rules.yml`.
- To verify rules are loaded:

```bash
# on the server where Prometheus runs
docker exec -it prometheus curl -s http://localhost:9090/api/v1/rules | jq '.'
# or open http://SERVER_IP:9090/rules
```

Testing alerts (example: BackendDown)

1) Confirm the backend target is configured in Prometheus: inspect the `backend` job in [monitoring/prometheus/prometheus.yml](monitoring/prometheus/prometheus.yml). Prometheus scrapes `backend:4000` as defined.
2) Stop the backend container:

```bash
docker stop backend_server
```

3) Check Prometheus targets and expected scrape error:

```bash
# list active targets and their health
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {scrapePool, scrapeUrl, lastError, health}'
```

You may see an error like: "lookup backend on 127.0.0.11:53: server misbehaving" — this is a DNS / resolution message from Docker's internal resolver and indicates Prometheus cannot reach the `backend` service (expected when backend is stopped). When this scrape fails, the metric `up{job="backend"}` becomes 0 and the alert `BackendDown` (defined with `for: 30s`) will fire after the evaluation interval.

4) Verify alerts:

```bash
# check active alerts
curl -s http://localhost:9090/api/v1/alerts | jq '.'
# or open http://SERVER_IP:9090/alerts
```

If you do not see the alert fire:
- Confirm Prometheus loaded the alert rules (see commands above).
- Check Prometheus logs for rule load errors:

```bash
docker logs --since 1h prometheus | tail -n 200
```

Alertmanager: notifications and receivers

- Alertmanager config is in [monitoring/alertmanager/alertmanager.yml](monitoring/alertmanager/alertmanager.yml). By default it contains a minimal `default` receiver that only logs.
- To receive notifications (Slack, email, webhook), add a receiver to the Alertmanager config and mount any secret credentials via environment variables or Docker secrets. Example Slack receiver snippet:

```yaml
receivers:
  - name: 'slack-webhook'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXXXX/YYYYY/ZZZZZ'
        channel: '#alerts'
```

After editing Alertmanager config, restart the Alertmanager container:

```bash
docker compose -f docker-compose-monitor.yml up -d alertmanager
```

Common troubleshooting

- No alerts showing when a service is down:
  - **Possible cause:** alert rules not mounted into Prometheus or Prometheus failed to parse them.
  - **Fix:** Ensure `monitoring/prometheus/alert-rules.yml` is mounted in `docker-compose-monitor.yml` and restart Prometheus.

- Prometheus shows target scrape errors like `server misbehaving`:
  - **Cause:** Docker DNS resolver returned an error while resolving the service name (this is the scrape failure). This is expected when the target container is stopped.
  - **Fix:** Verify the target container name in `docker-compose.yml` matches the target in `prometheus.yml` (service name `backend`), and ensure both are on the same Docker network `devops`.

- Prometheus not on same network as services:
  - **Fix:** Make sure the `devops` Docker network exists and both compose stacks are attached to it. Create it with:

```bash
docker network create devops
```

Advanced: deploying to production

- There are example helper scripts in [deploy/](deploy) for a blue/green backend deployment. Review and adapt environment variables before using on production.
- Secure Grafana and Alertmanager UIs with proper authentication and firewall rules.
- For high availability, run Prometheus and Alertmanager in replicated setups and use persistent volumes for storage.

Contributing

- Add issues or PRs for improvements. Keep monitoring configurations small and well-documented.

Contact

- For questions about this repository, add an issue to the repo or contact the maintainer listed in the project metadata.

License

- This repository does not include an explicit license file. Add one before sharing publicly if needed.
