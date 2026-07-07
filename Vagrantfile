if File.exist?(".env")
  File.foreach(".env") do |line|
    next if line.strip.start_with?("#") || line.strip.empty?
    key, value = line.strip.split("=", 2)
    ENV[key] = value.gsub(/\A['"]|['"]\z/, '') if key && value
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.boot_timeout = 3600

  devops_pub_key_path = File.expand_path("~/.ssh/devops_key.pub")
  backup_pub_key_path = File.expand_path("~/.ssh/backup_key.pub")
  backup_priv_key_path = File.expand_path("~/.ssh/backup_key")

  devops_password = (ENV['DEVOPS_PASSWORD'] && !ENV['DEVOPS_PASSWORD'].empty?) ? ENV['DEVOPS_PASSWORD'] : (ARGV[0] != "destroy" && abort("ERROR: DEVOPS_PASSWORD not set. Add it to your .env file"))

  if ARGV[0] != "destroy"
    abort "ERROR: SSH public key not found at ~/.ssh/devops_key.pub" unless File.exist?(devops_pub_key_path)
    abort "ERROR: Backup public key not found at ~/.ssh/backup_key.pub" unless File.exist?(backup_pub_key_path)
    abort "ERROR: Backup private key not found at ~/.ssh/backup_key" unless File.exist?(backup_priv_key_path)
  end

  devops_pub_key = File.exist?(devops_pub_key_path) ? File.read(devops_pub_key_path).strip : ""
  backup_pub_key = File.exist?(backup_pub_key_path) ? File.read(backup_pub_key_path).strip : ""

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
  end

  config.vm.provision "shell", path: "scripts/provision.sh", args: [devops_pub_key, devops_password, backup_pub_key, ENV['APT_CACHE_URL'] || ""]

  config.vm.define "loadbalancer" do |lb|
    lb.vm.hostname = "loadbalancer"
    lb.vm.network "private_network", ip: "192.168.56.10"
    lb.vm.provider "virtualbox" do |vb|
      vb.name = "loadbalancer"
      vb.memory = "2048"
      vb.cpus = 2
    end
    lb.vm.provision "shell", path: "scripts/loadbalancer.sh"
  end

  config.vm.define "webserver01" do |ws1|
    ws1.vm.hostname = "webserver01"
    ws1.vm.network "private_network", ip: "192.168.56.11"
    ws1.vm.provider "virtualbox" do |vb|
      vb.name = "webserver01"
      vb.memory = "1024"
      vb.cpus = 1
    end
    ws1.vm.provision "shell", path: "scripts/docker.sh"
    ws1.vm.provision "shell", path: "scripts/frontend.sh"
  end

  config.vm.define "webserver02" do |ws2|
    ws2.vm.hostname = "webserver02"
    ws2.vm.network "private_network", ip: "192.168.56.12"
    ws2.vm.provider "virtualbox" do |vb|
      vb.name = "webserver02"
      vb.memory = "1024"
      vb.cpus = 1
    end
    ws2.vm.provision "shell", path: "scripts/docker.sh"
    ws2.vm.provision "shell", path: "scripts/frontend.sh"
  end

  config.vm.define "appserver" do |app|
    app.vm.hostname = "appserver"
    app.vm.network "private_network", ip: "192.168.56.20"
    app.vm.provider "virtualbox" do |vb|
      vb.name = "appserver"
      vb.memory = "2048"
      vb.cpus = 2
    end
    app.vm.provision "shell", path: "scripts/docker.sh"
    app.vm.provision "shell", path: "scripts/backend.sh"
  end

  config.vm.define "backup" do |bkp|
    bkp.vm.hostname = "backup"
    bkp.vm.network "private_network", ip: "192.168.56.30"
    bkp.vm.provider "virtualbox" do |vb|
      vb.name = "backup"
      vb.memory = "1024"
      vb.cpus = 1
    end
    bkp.vm.provision "file", source: "~/.ssh/backup_key", destination: "/tmp/backup_key"
    bkp.vm.provision "shell", path: "scripts/backup.sh"
  end
end