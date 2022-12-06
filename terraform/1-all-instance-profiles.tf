###########################
# Standard Instance role  #
###########################

# This setups the standard perms for an instance
# This is the top record the instance profile record
resource "aws_iam_instance_profile" "instance-profile" {
  name = "instance-profile"
  role = aws_iam_role.iam-role.name
}

resource "aws_iam_role" "iam-role" {
  name               = "iam-role"
  assume_role_policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Action": "sts:AssumeRole",
			"Principal": {
				"Service": "ec2.amazonaws.com"
			},
			"Effect": "Allow",
			"Sid": ""
		}
	]
}
EOF
}

# allow the instance to read tags, so it can work out how to configure itself
resource "aws_iam_role_policy_attachment" "describe-tags" {
  role       = aws_iam_role.iam-role.name
  policy_arn = aws_iam_policy.describe-tags-policy.arn
}

resource "aws_iam_policy" "describe-tags-policy" {
  name        = "describe-app-tags"
  description = "Allow container to read its own tags"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2:DescribeTags",
            "Resource": "*"
        }
    ]
}
EOF
}

# Calix secrets
resource "aws_iam_role_policy_attachment" "calix-secret" {
  role       = aws_iam_role.iam-role.name
  policy_arn = aws_iam_policy.calix-secret-policy.arn
}

resource "aws_iam_policy" "calix-secret-policy" {
  name        = "calix-secret"
  description = "Calix secrets"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "VisualEditor0"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetRandomPassword",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      Resource = [
        "arn:aws:secretsmanager:eu-west-2::secret:dev/calix/elastic-bXOADl",
        "arn:aws:secretsmanager:eu-west-2::secret:dev/calix/activate-qTb7xY",
        "arn:aws:secretsmanager:eu-west-2::secret:prod/calix/activate-EZQWic",
        "arn:aws:secretsmanager:eu-west-2::secret:prod/calix/elastic-zkFBZv",
      ]
    }]
  })
}


# Solarwinds secrets
resource "aws_iam_role_policy_attachment" "solarwinds-secret" {
  role       = aws_iam_role.iam-role.name
  policy_arn = aws_iam_policy.solarwinds-secret-policy.arn
}

# Solarwinds secrets
resource "aws_iam_policy" "solarwinds-secret-policy" {
  name        = "solarwinds-secret"
  description = "Secrets for solarwinds"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "VisualEditor0"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetRandomPassword",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      Resource = [
        "arn:aws:secretsmanager:eu-west-2::secret:prod/mssql/solarwinds-rPo4T3",
        "arn:aws:secretsmanager:eu-west-2::secret:dev/mssql/solarwinds-lH4wrk"
      ]
    }]
  })
}

# Netbox secrets
resource "aws_iam_role_policy_attachment" "netbox-secret" {
  role       = aws_iam_role.iam-role.name
  policy_arn = aws_iam_policy.netbox-secret-policy.arn
}

# Nebox secrets
resource "aws_iam_policy" "netbox-secret-policy" {
  name        = "netbox-secret"
  description = "Secrets for netbox"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "VisualEditor0"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetRandomPassword",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      Resource = [
        "arn:aws:secretsmanager:eu-west-2::secret:prod/netbox/postgres-SXbRNI",
        "arn:aws:secretsmanager:eu-west-2::secret:dev/netbox/postgres-81Etn4"
      ]
    }]
  })
}

# Boot secret
resource "aws_iam_role_policy_attachment" "all-boot-secret" {
  role       = aws_iam_role.iam-role.name
  policy_arn = aws_iam_policy.boot-secret-policy.arn
}

resource "aws_iam_policy" "boot-secret-policy" {
  name        = "boot-secret"
  description = "Secrets for booting instance"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "VisualEditor0"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetRandomPassword",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      Resource = [
        "arn:aws:secretsmanager:eu-west-2::secret:prod/deploy/key-RzL6kx",
        "arn:aws:secretsmanager:eu-west-2::secret:dev/deploy/key-nD6uNu"
      ]
    }]
  })
}

# Allow metadata
resource "aws_iam_role_policy_attachment" "describe-instances" {
  role       = aws_iam_role.iam-role.name
  policy_arn = aws_iam_policy.describe-instances-policy.arn
}

resource "aws_iam_policy" "describe-instances-policy" {
  name        = "describe-instances"
  description = "Allow container to access EC2 meta info"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ec2:DescribeInstances"
        Resource = "*"
      }
    ]
  })
}


# This is attaching an existing standard role - SSM-Policy 
# To allow SSM to work
resource "aws_iam_role_policy_attachment" "SSM-policy" {
  role       = aws_iam_role.iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# SSMManagedInstanceCore
# To allow SSM to work
resource "aws_iam_role_policy_attachment" "SSM-core-policy" {
  role       = aws_iam_role.iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EFS Full Access - Not configured 
#resource "aws_iam_role_policy_attachment" "NEW-EFS-policy" {
#  role       = aws_iam_role.iam-role.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
#}

# Backup S3 bucket policy
#This attaches the policy to the role and profile 
# Note the lack of quotes around the policy_arn!
resource "aws_iam_role_policy_attachment" "S3-backup-policy" {
  role       = aws_iam_role.iam-role.name
  policy_arn = aws_iam_policy.container-S3-backup.arn
}

## - Buckets are permanent, so they need to be created manually
resource "aws_iam_policy" "container-S3-backup" {
  name        = "container-s3-backup"
  description = "S3 lf access policy"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::bucket-infra/*",
                "arn:aws:s3:::bucket-infra"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:GetObjectTagging",
                "s3:PutObjectTagging",
                "s3:PutObjectVersionTagging"
            ],
            "Resource": [
                "arn:aws:s3:::bucket-infra/*",
                "arn:aws:s3:::bucket-infra"
            ]
        }
    ]
}
EOF
}

