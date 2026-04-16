program assume_realloc_lhs
   implicit none
   integer, allocatable :: x(:)
   allocate( x(2) )
   print *, "Before assignment x(2): shape(x) = ", shape(x)
   x = [ 1, 2, 3 ]
   print *, "After assignment [1,2,3]: shape(x) = ", shape(x)
end program assume_realloc_lhs
