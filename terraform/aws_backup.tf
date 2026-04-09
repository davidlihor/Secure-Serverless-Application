resource "aws_backup_vault" "dynamodb_vault" {
  count       = var.is_production ? 1 : 0
  name        = "${var.project_name}-backup-vault"
  kms_key_arn = aws_kms_key.backup_key[0].arn
}

resource "aws_backup_plan" "dynamodb_plan" {
  count = var.is_production ? 1 : 0
  name  = "${var.project_name}-backup-plan"

  rule {
    rule_name         = "daily-backup-90-days-retention"
    target_vault_name = aws_backup_vault.dynamodb_vault[0].name
    schedule          = "cron(0 12 * * ? *)"

    lifecycle {
      delete_after = 90
    }
  }
}

resource "aws_iam_role" "backup_role" {
  count = var.is_production ? 1 : 0
  name  = "${var.project_name}-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  count      = var.is_production ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role[0].name
}

resource "aws_iam_role_policy_attachment" "restore_policy" {
  count      = var.is_production ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup_role[0].name
}

resource "aws_backup_selection" "dynamodb_selection" {
  count = var.is_production ? 1 : 0
  name  = "${var.project_name}-selection"

  iam_role_arn = aws_iam_role.backup_role[0].arn
  plan_id      = aws_backup_plan.dynamodb_plan[0].id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = var.project_name
  }
}