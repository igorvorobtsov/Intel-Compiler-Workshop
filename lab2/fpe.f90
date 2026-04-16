program fpe
    implicit none
    real :: a, b

    b = 3.0
    a = b / 0.0    ! Division by zero - floating point exception

    print *, a
end program fpe
