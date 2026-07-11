# Firebase Analytics Cohort Funnels

This document defines the recommended Exploration / BigQuery funnels for NoiseRecord.
User property `install_cohort` and `install_date` (format `yyyy-MM-dd`) are set on first cold launch via `LaunchExperienceStore.recordFirstInstallIfNeeded()`.

## Activation funnel

Segment by `install_cohort` (user property).

| Step | Event | Notes |
|------|-------|-------|
| 1 | `first_open` | Firebase automatic |
| 2 | `product_time_to_first_db` | Params: `elapsed_ms`, `db` |
| 3 | `monitor_start` | Core activation |
| 4 | `product_monitor_session_duration` | Filter `bucket` in (`2m_10m`, `gte_10m`) |

## Monetization funnel

| Step | Event | Notes |
|------|-------|-------|
| 1 | `commercial_paywall_shown` | Param: `context` |
| 2 | `product_paywall_purchase_tap` | Param: `context`, `tier` |
| 3 | `commercial_iap_purchase_success` | StoreKit verified |
| 4 | `app_store_subscription_convert` | Revenue event |

Paywall frequency cap emits `product_paywall_suppressed` with `reason=frequency_cap` when launch paywall is blocked.

## Retention proxies

- `app_launch` events per user per day
- D1 return: users with `monitor_start` on install day AND day+1
- `product_tab_selected` by `tab` parameter

## Quality monitoring

- Ad failure rate: `commercial_ad_fail / (commercial_ad_show + commercial_ad_fail)` by `channel`, `step`
- Error rate: unique users with `app_error` / DAU
- First-install ad skip: `ad.cold.skipped_first_install_day` breadcrumbs in Crashlytics

## Onboarding tasks

| Step | Event |
|------|-------|
| Task 1 start | `product_onboarding_step_viewed` step=1 |
| Task 1 done | `product_onboarding_task_completed` task=measure_10s |
| Task 2 shown | `product_onboarding_step_viewed` step=2 |
| Task 2 done | `product_onboarding_task_completed` task=visit_voice |
| Skip | `product_onboarding_dismissed` |

## Sleep activation

| Step | Event |
|------|-------|
| Scheduled | `product_sleep_overnight_activation_scheduled` |
| Started | `product_sleep_start_tap` |
| Report | `product_sleep_report_open` |

## BigQuery export (optional)

1. Firebase Console → Project Settings → Integrations → BigQuery
2. Enable daily export
3. Sample activation query:

```sql
SELECT
  user_pseudo_id,
  MIN(IF(event_name = 'first_open', event_timestamp, NULL)) AS first_open_ts,
  MIN(IF(event_name = 'product_time_to_first_db', event_timestamp, NULL)) AS first_db_ts,
  MIN(IF(event_name = 'monitor_start', event_timestamp, NULL)) AS monitor_start_ts
FROM `project.analytics_xxx.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20260701' AND '20260731'
GROUP BY 1
```

Compare cohorts by `user_properties.install_cohort.value.string_value`.
