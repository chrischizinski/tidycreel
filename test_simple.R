# Simple test function to verify Kilocode functionality
test_function <- function(x, y) {
  result <- x + y
  cat("Sum of", x, "and", y, "is:", result, "\n")
  return(result)
}

# Test the function
test_function(5, 3)