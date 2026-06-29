resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.project_name}-access-analyzer"
  type          = "ACCOUNT"

  tags = {
    Name = "${var.project_name}-access-analyzer"
  }
}
