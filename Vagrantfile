if File.exist?(".env")
  File.foreach(".env") do |line|
    if line =~ /\ADEVOPS_PASSWORD=(.*)\z/
      ENV['DEVOPS_PASSWORD'] = $1.strip.gsub(/\A['"]|['"]\z/, '')
      break
    end
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.boot_timeout = 3600
  devops_pub_key_path = File.expand_path("~/.ssh/devops_key.pub")
  devops_password = ENV['DEVOPS_PASSWORD'] || (ARGV[0] != "destroy" && abort("ERROR: DEVOPS_PASSWORD not set. Run with DEVOPS_PASSWORD=yourpassword vagrant up"))

  if !File.exist?(devops_pub_key_path) && ARGV[0] != "destroy"
    abort "ERROR: SSH public key not found at \"~/.ssh/devops_key.pub\" Please generate one first."
  end

  devops_pub_key = File.exist?(devops_pub_key_path) ? File.read(devops_pub_key_path).strip : ""
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--biosbootmenu", "disabled"]
    vb.customize ["modifyvm", :id, "--audio", "none"]
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.gui = false
  end

  config.vm.provision "shell", path: "scripts/provision.sh", args: [devops_pub_key, devops_password]
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