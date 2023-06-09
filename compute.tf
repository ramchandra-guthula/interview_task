

resource "aws_instance" "task_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.myapp-private-subnet.id
  vpc_security_group_ids = [aws_security_group.ssh_connection.id]
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.name
  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    volume_size = var.ebs_volume_size
    encrypted   = true
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo mkdir /mnt/interview_task && cd /mnt/interview_task
              sudo mkfs.ext4 /dev/xvdf
              sudo mount /dev/xvdf /mnt/interview_task
              sudo chown ec2-user:ec2-user /mnt/interview_task
              sudo yum -y install python3
              aws s3 cp "s3://${aws_s3_bucket.python_script.bucket}/python_script.py" .
              python3 /mnt/interview_task/python_script.py > /mnt/interview_task/output.txt
              aws s3 cp output.txt "s3://${aws_s3_bucket.python_script.bucket}/"
              EOF

  ebs_block_device {
    device_name = "/dev/xvdf"
    volume_size = var.ebs_volume_size
  }

  tags = local.env_tags
  # depends_on = [
  #   aws_iam_instance_profile.instance_profile,
  #   aws_s3_bucket.python_script

  # ]
}


resource "aws_security_group" "ssh_connection" {
  name        = "interview-test-sg"
  vpc_id      = aws_vpc.myapp-vpc.id
  description = "Allow SSH inbound traffic"
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] #[aws_vpc.main.cidr_block]
  }

  ingress {
    description = "HTTP access from any where"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name = "allow_ssh"
  }
}