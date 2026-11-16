output "addon_versions" {
  description = "Installed add-on versions, keyed by add-on name."
  value       = { for k, a in aws_eks_addon.this : k => a.addon_version }
}
