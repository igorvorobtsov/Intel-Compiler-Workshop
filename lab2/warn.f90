program warn
    implicit none
    real :: afunc, b
    integer :: abc

    ! abc is declared but not used
    afunc(b) = 123*b

    print *, "Done"
end program warn
