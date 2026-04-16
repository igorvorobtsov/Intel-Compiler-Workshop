module m
    implicit none
    type :: t
    end type
    contains
        pure subroutine sub(x)
            class(t), allocatable, intent(out) :: x
            allocate(x)
        end subroutine
end module m

program standard
    use m
    implicit none

    print *, "Testing standard conformance"
end program standard
