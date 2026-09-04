resource "aws_cloudwatch_log_group" "syslog" {
  name              = "/vpn-server/syslog"
  retention_in_days = 30
}

resource "aws_cloudwatch_dashboard" "vpn_dashboard" {
  dashboard_name = "vpn-server-dashboard-${var.aws_region}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", aws_autoscaling_group.vpn.name],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", aws_autoscaling_group.vpn.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "VPN Network Traffic (${var.aws_region})"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.vpn.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "VPN CPU Utilization (${var.aws_region})"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "AutoScalingGroupName", aws_autoscaling_group.vpn.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Status Checks Failed (${var.aws_region})"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["CWAgent", "mem_used_percent", "AutoScalingGroupName", aws_autoscaling_group.vpn.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Memory Utilization (%)"
        }
      }
    ]
  })
}
