cmake_minimum_required(VERSION 3.15)

# Simple client example
add_executable(simple_client simple_client.c)
target_link_libraries(simple_client ea_aol)

# Install examples
install(TARGETS simple_client
    RUNTIME DESTINATION bin/examples
)
