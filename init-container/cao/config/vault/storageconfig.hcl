# disable memory locking. Memory locking is a security measure that prevents sensitive data from being swapped to disk, but it can cause issues on certain systems. 
disable_mlock = true
ui = true
    
# a listener configuration for TCP connections.
listener "tcp" {
  tls_disable = 1
  address = "[::]:8200"
  cluster_address = "[::]:8201"
}

storage "raft" {
  path = "/vault/data"
}
