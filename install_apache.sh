#! /bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
echo "<h1>Hello from $(curl http://169.254.169.254/latest/meta-data/instance-id)</h1>" | sudo tee /var/www/html/index.html