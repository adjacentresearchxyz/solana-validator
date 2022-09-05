{lib}: let
  # docker's filesystems disappear quickly, leading to false positives
  deviceFilter = ''path!~"^(/var/lib/docker|/nix/store).*"'';
in
  lib.mapAttrsToList
  (name: opts: {
    alert = name;
    expr = opts.condition;
    for = opts.time or "2m";
    labels = {};
    annotations.description = opts.description;
  })
  ({
      prometheus_too_many_restarts = {
        condition = ''changes(process_start_time_seconds{job=~"prometheus|alertmanager"}[15m]) > 2'';
        description = "Prometheus has restarted more than twice in the last 15 minutes. It might be crashlooping";
        summary = "Prometheus has restarted more than twice in the last 15 minutes";  
      };

      alert_manager_config_not_synced = {
        condition = ''count(count_values("config_hash", alertmanager_config_hash)) > 1'';
        description = "Configurations of AlertManager cluster instances are out of sync";
        summary = "Configurations of AlertManager cluster instances are out of sync";
      };

      prometheus_not_connected_to_alertmanager = {
        condition = "prometheus_notifications_alertmanagers_discovered < 1";
        description = "Prometheus cannot connect the alertmanager\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
        summary = "Prometheus cannot connect the alertmanager";
      };

      prometheus_rule_evaluation_failures = {
        condition = "increase(prometheus_rule_evaluation_failures_total[3m]) > 0";
        description = "Prometheus encountered {{ $value }} rule evaluation failures, leading to potentially ignored alerts.\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
        summary = "Prometheus encountered {{ $value }} rule evaluation failures"; 
      };

      promtail_request_errors = {
        condition = ''100 * sum(rate(promtail_request_duration_seconds_count{status_code=~"5..|failed"}[1m])) by (namespace, job, route, instance) / sum(rate(promtail_request_duration_seconds_count[1m])) by (namespace, job, route, instance) > 10'';
        time = "15m";
        description = ''{{ $labels.job }} {{ $labels.route }} is experiencing {{ printf "%.2f" $value }}% errors'';
        summary = "{{ $labels.job }} {{ $labels.route }} is experiencing errors";
      };

      promtail_file_lagging = {
        condition = ''abs(promtail_file_bytes_total - promtail_read_bytes_total) > 1e6'';
        time = "15m";
        description = ''{{ $labels.instance }} {{ $labels.job }} {{ $labels.path }} has been lagging by more than 1MB for more than 15m'';
        summary = "{{ $labels.instance }} {{ $labels.job }} {{ $labels.path }} has been lagging by more than for more than 15m";
      };

      filesystem_full_80percent = {
        condition = ''disk_used_percent{job="adjacent",mountpoint="/",fstype!="rootfs"} >= 80'';
        time = "10m";
        description = "{{$labels.instance}} device {{$labels.device}} on {{$labels.path}} got less than 20% space left on its filesystem";
        summary = "{{$labels.instance}} device {{$labels.device}} on {{$labels.path}} got less than 20% space left on its filesystem";
      };

     swap_using_30percent = {
        condition = ''mem_swap_total{} - (mem_swap_cached + mem_swap_free) > mem_swap_total * 0.3'';
        time = "30m";
        description = "{{$labels.host}} is using 30% of its swap space for at least 30 minutes";
        summary = "{{$labels.host}} is using 30% of its swap space for at least 30 minutes";
      };

      ping = {
        condition = "ping_result_code{type!='mobile'} != 0";
        description = "{{$labels.url}}: ping from {{$labels.instance}} has failed";
        summary = "{{$labels.url}}: ping from {{$labels.instance}} has failed";
      };

      ping_high_latency = {
        condition = "ping_average_response_ms{type!='mobile'} > 5000";
        description = "{{$labels.instance}}: ping probe from {{$labels.source}} is encountering high latency";
        summary = "{{$labels.instance}}: ping probe from {{$labels.source}} is encountering high latency";
      };

      host_unusual_network_throughput_in = {
        condition = "sum by (instance) (rate(node_network_receive_bytes_total[2m])) / 1024 / 1024 > 100";
        description = "Host network interfaces are probably receiving too much data (> 100 MB/s)\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
        summary = "Host unusual network throughput in (instance {{ $labels.instance }})";
      };

      host_unusual_network_throughput_out = {
        condition = "sum by (instance) (rate(node_network_transmit_bytes_total[2m])) / 1024 / 1024 > 100";
        description = "Host network interfaces are probably sending too much data (> 100 MB/s)\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
        summary = "Host unusual network throughput out (instance {{ $labels.instance }})";
      };
  }
  )
