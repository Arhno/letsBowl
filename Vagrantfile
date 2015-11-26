# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"

  config.vm.network "forwarded_port", guest: 3000, host: 3000

  config.vm.provision "shell", inline: <<-SHELL
    sudo add-apt-repository -y ppa:brightbox/ruby-ng
    sudo apt-get -y update
    sudo apt-get -y dist-upgrade
    sudo apt-get -y install ruby2.2
    sudo apt-get -y install ruby2.2-dev
    sudo apt-get -y install zlib1g-dev
    sudo apt-get -y install libopencv-dev
    sudo apt-get -y install cmake
    sudo apt-get -y install libsqlite3-dev
    sudo apt-get -y install nodejs

    sudo update-alternatives --set ruby /usr/bin/ruby2.2
    sudo update-alternatives --set gem /usr/bin/gem2.2
    sudo gem install bundler

    cd /vagrant

    bundle install
    rake db:create
    rake db:migrate
    rake db:seed

    rails s -p 3000 -b 0.0.0.0 -d

  SHELL
end
