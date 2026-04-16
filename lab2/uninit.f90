program uninit
    implicit none
    real :: a, b

    ! b is not initialized - undefined behavior
    a = b / 0.0

    print *, a
end program uninit
